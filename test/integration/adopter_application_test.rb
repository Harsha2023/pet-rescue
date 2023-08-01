require "test_helper"

class AdopterApplicationTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create(:organization)
    @pet_id = create(:pet, organization: @organization).id
  end

  test "adopter user without profile cannot apply for pet and sees flash error" do
    user = create(:user)
    sign_in user
    before_count = AdopterApplication.all.count

    post "/create_my_application",
      params: {application:
        {
          adopter_account_id: user.id,
          pet_id: @pet_id
        }}

    assert_response :redirect
    follow_redirect!
    assert_equal "Unauthorized action.", flash[:alert]

    assert_equal before_count, AdopterApplication.all.count
  end

  test "staff user sees flash error if they apply for a pet" do
    verified_staff = create(:user, :verified_staff)
    sign_in verified_staff
    before_count = AdopterApplication.all.count

    post "/create_my_application",
      params: {application:
        {
          adopter_account_id: nil,
          pet_id: @pet_id
        }}

    assert_response :redirect
    follow_redirect!
    assert_equal "Unauthorized action.", flash[:alert]

    assert_equal before_count, AdopterApplication.all.count
  end

  test "adopter user with profile can apply for a pet and staff receive email" do
    verified_staff = create(:staff_account, organization: @organization)
    org_staff = create(:user, staff_account: verified_staff)
    adopter_with_profile = create(:user, :adopter_with_profile)
    sign_in adopter_with_profile
    before_count = AdopterApplication.all.count

    post "/create_my_application",
      params: {application:
        {
          adopter_account_id: adopter_with_profile.adopter_account.id,
          pet_id: @pet_id
        }}

    assert_response :redirect
    follow_redirect!
    assert flash[:notice].include?("Application submitted!")
    assert_equal AdopterApplication.all.count, before_count + 1

    mail = ActionMailer::Base.deliveries
    assert_equal mail[0].from.join, "bajapetrescue@gmail.com", "from email is incorrect"
    assert_equal mail[0].to.join(" "), org_staff.email, "to email is incorrect"
    assert_equal mail[0].subject, "New Adoption Application", "subject is incorrect"
  end

  test "adopter user with profile cannot apply for a paused pet and sees flash error" do
    paused_pet = create(:pet, :application_paused_opening_soon)
    adopter_with_profile = create(:user, :adopter_with_profile)
    sign_in adopter_with_profile
    before_count = AdopterApplication.all.count

    post "/create_my_application",
      params: {application:
        {
          adopter_account_id: adopter_with_profile.adopter_account.id,
          pet_id: paused_pet.id
        }}

    assert_response :redirect
    follow_redirect!
    assert_equal "Applications are paused for this pet", flash[:alert]

    assert_equal before_count, AdopterApplication.all.count
  end
end
